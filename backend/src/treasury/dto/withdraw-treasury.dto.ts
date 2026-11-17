import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

export class WithdrawTreasuryDto {
  @IsIn(['all', 'leave', 'amount'])
  mode: 'all' | 'leave' | 'amount';

  @ValidateIf((dto: WithdrawTreasuryDto) => dto.mode === 'leave')
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  leaveAmount?: number;

  @ValidateIf((dto: WithdrawTreasuryDto) => dto.mode === 'amount')
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  withdrawAmount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
