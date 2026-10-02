import {
  IsNumber,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class ProfitQrCashOutDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  cashAmount: number;

  @IsOptional()
  @IsIn(['cash', 'deduct'])
  commissionMethod: 'cash' | 'deduct' = 'deduct';

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;
}
