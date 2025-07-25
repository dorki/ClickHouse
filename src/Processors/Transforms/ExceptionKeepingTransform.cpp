#include <exception>
#include <Processors/Transforms/ExceptionKeepingTransform.h>
#include <Common/ThreadStatus.h>
#include <Common/Stopwatch.h>
#include <base/scope_guard.h>

namespace DB
{

namespace ErrorCodes
{
    extern const int LOGICAL_ERROR;
}

ExceptionKeepingTransform::ExceptionKeepingTransform(SharedHeader in_header, SharedHeader out_header, bool ignore_on_start_and_finish_)
    : IProcessor({in_header}, {out_header})
    , input(inputs.front()), output(outputs.front())
    , ignore_on_start_and_finish(ignore_on_start_and_finish_)
{
}

IProcessor::Status ExceptionKeepingTransform::prepare()
{
    if (stage == Stage::Start)
    {
        if (ignore_on_start_and_finish)
            stage = Stage::Consume;
        else
            return Status::Ready;
    }

    /// Check can output.

    if (output.isFinished())
        throw Exception(ErrorCodes::LOGICAL_ERROR, "Output port is finished for {}", getName());

    if (!output.canPush())
    {
        input.setNotNeeded();
        return Status::PortFull;
    }

    /// Output if has data.
    if (ready_output)
    {
        output.pushData(std::move(data));
        ready_output = false;
        return Status::PortFull;
    }

    if (stage == Stage::Generate)
        return Status::Ready;

    while (!ready_input)
    {
        if (input.isFinished())
        {
            if (stage != Stage::Exception && stage != Stage::Finish)
            {
                stage = Stage::Finish;
                if (!ignore_on_start_and_finish)
                    return Status::Ready;
            }

            output.finish();
            return Status::Finished;
        }

        input.setNeeded();

        if (!input.hasData())
            return Status::NeedData;

        data = input.pullData(true);

        if (data.exception)
        {
            stage = Stage::Exception;
            onException(data.exception);
            output.pushData(std::move(data));
            return Status::PortFull;
        }

        if (stage == Stage::Exception)
            /// In case of exception, just drop all other data.
            /// If transform is stateful, it's state may be broken after exception from transform()
            data.chunk.clear();
        else
            ready_input = true;
    }

    return Status::Ready;
}

static std::exception_ptr runStep(std::function<void()> step, ThreadGroupPtr & thread_group)
{
    ThreadGroupSwitcher switcher(thread_group, "RuntimeData", /*allow_existing_group*/ true);

    std::exception_ptr res;

    try
    {
        step();
    }
    catch (...)
    {
        res = std::current_exception();
    }

    return res;
}

void ExceptionKeepingTransform::work()
{
    if (stage == Stage::Start)
    {
        stage = Stage::Consume;

        if (auto exception = runStep([this] { onStart(); }, thread_group))
        {
            stage = Stage::Exception;
            ready_output = true;
            data.exception = exception;
            onException(data.exception);
            cancel();
        }
    }
    else if (stage == Stage::Consume || stage == Stage::Generate)
    {
        if (stage == Stage::Consume)
        {
            ready_input = false;

            if (auto exception = runStep([this] { onConsume(std::move(data.chunk)); }, thread_group))
            {
                stage = Stage::Exception;
                ready_output = true;
                data.exception = exception;
                onException(data.exception);
                cancel();
            }
            else
                stage = Stage::Generate;
        }

        if (stage == Stage::Generate)
        {
            GenerateResult res;
            if (auto exception = runStep([this, &res] { res = onGenerate(); }, thread_group))
            {
                stage = Stage::Exception;
                ready_output = true;
                data.exception = exception;
                onException(data.exception);
                cancel();
            }
            else
            {
                if (res.chunk)
                {
                    data.chunk = std::move(res.chunk);
                    ready_output = true;
                }

                if (res.is_done)
                    stage = Stage::Consume;
            }
        }
    }
    else if (stage == Stage::Finish)
    {
        if (auto exception = runStep([this] { onFinish(); }, thread_group))
        {
            stage = Stage::Exception;
            ready_output = true;
            data.exception = exception;
            onException(data.exception);
            cancel();
        }
    }
}

void ExceptionKeepingTransform::setRuntimeData(ThreadGroupPtr thread_group_)
{
    thread_group = thread_group_;
}

}
