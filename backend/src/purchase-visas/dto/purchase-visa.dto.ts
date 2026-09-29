import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreatePurchaseVisaDto {
  @IsString()
  @MaxLength(150)
  name: string;

  @IsString()
  @MaxLength(23)
  cardNumber: string;

  @IsString()
  @MaxLength(120)
  ownerName: string;

  /** Card expiry as MM/YY. */
  @IsString()
  @MaxLength(5)
  expiry: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}

export class WithdrawPurchaseVisaDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsString()
  @MaxLength(150)
  agentName: string;

  @IsBoolean()
  withService: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
