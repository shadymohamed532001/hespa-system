import { IsInt, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class SellProductDto {
  @IsInt()
  @Min(1)
  quantity: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  unitPrice: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
