import { IsEnum, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';
import { AccountType } from '../../database/enums.js';

export class CreateAccountDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name: string;

  @IsEnum(AccountType)
  type: AccountType;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}
