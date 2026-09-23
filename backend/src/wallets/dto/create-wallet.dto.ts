import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateWalletDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  ownerName?: string;

  @IsIn([
    'vodafone_cash',
    'orange_cash',
    'etisalat_cash',
    'we_pay',
    'instapay',
    'other_wallet',
    'wallet',
  ])
  type: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}
