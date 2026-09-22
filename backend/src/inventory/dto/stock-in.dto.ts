import { IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class StockInDto {
  @IsInt()
  @Min(1)
  quantity: number;

  @IsOptional()
  @IsString()
  note?: string;
}
