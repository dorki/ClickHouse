#pragma once

#include <Processors/Formats/IRowOutputFormat.h>


namespace DB
{

class WriteBuffer;


/** This format only allows to output columns of type String
  *  or types that have contiguous representation in memory.
  * They are output as raw bytes without any delimiters or escaping.
  *
  * The difference between RawBLOB and TSVRaw:
  * - data is output in binary, no escaping;
  * - no delimiters between values;
  * - no newline at the end of each value.
  *
  * The difference between RawBLOB and RowBinary:
  * - strings are output without their lengths.
  *
  * If you are output more than one value, the output format is ambiguous and you may not be able to read data back.
  */
class RawBLOBRowOutputFormat final : public IRowOutputFormat
{
public:
    RawBLOBRowOutputFormat(
        WriteBuffer & out_,
        SharedHeader header_);

    String getName() const override { return "RawBLOBRowOutputFormat"; }

private:
    void writeField(const IColumn & column, const ISerialization &, size_t row_num) override;
};

}
