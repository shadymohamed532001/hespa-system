import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class TopUpAccountDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsOptional()
  @IsString()
  reference?: string;
}

