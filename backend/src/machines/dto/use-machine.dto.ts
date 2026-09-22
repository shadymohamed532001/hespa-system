import { IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class UseMachineDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  commission: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;
}
