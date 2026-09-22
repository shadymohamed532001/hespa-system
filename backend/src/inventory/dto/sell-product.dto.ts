import { IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class SellProductDto {
  @IsInt()
  @Min(1)
  quantity: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  unitPrice: number;

  @IsOptional()
  @IsString()
  note?: string;
}
