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
  @IsIn(['all', 'leave'])
  mode: 'all' | 'leave';

  @ValidateIf((dto: WithdrawTreasuryDto) => dto.mode === 'leave')
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  leaveAmount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
