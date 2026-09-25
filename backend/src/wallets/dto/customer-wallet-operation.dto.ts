import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CustomerWalletOperationDto {
  @IsIn(['send', 'receive'])
  direction: 'send' | 'receive';

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsOptional()
  @IsIn(['deducted', 'separate'])
  feePaymentMode?: 'deducted' | 'separate';

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  purpose?: string;
}
