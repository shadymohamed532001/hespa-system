import { IsEnum, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { AccountType } from '../../database/enums.js';

export class CreateAccountDto {
  @IsString()
  name: string;

  @IsEnum(AccountType)
  type: AccountType;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}

