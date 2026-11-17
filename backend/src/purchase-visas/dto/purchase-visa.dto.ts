import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

export class CreatePurchaseVisaDto {
  @IsString()
  @MaxLength(150)
  name: string;

  /** Optional: visas are now registered by holder name and balance only. */
  @IsOptional()
  @IsString()
  @MaxLength(23)
  cardNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  ownerName?: string;

  /** Optional card expiry as MM/YY; required only when cardNumber is sent. */
  @IsOptional()
  @IsString()
  @MaxLength(5)
  expiry?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  openingBalance = 0;
}

export class TopUpPurchaseVisaDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;
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

/** One-off withdrawal from an external purchase visa that is not registered. */
export class ExternalVisaWithdrawDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  holderName?: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  /** agent: the visa balance is supplied to an agent who pays cash.
   *  machine: the visa is used to load one of the shop's machines. */
  @IsOptional()
  @IsIn(['agent', 'machine'])
  destination?: 'agent' | 'machine';

  @ValidateIf((dto: ExternalVisaWithdrawDto) => dto.destination !== 'machine')
  @IsString()
  @MaxLength(150)
  agentName?: string;

  /** Optional: when set, the amount is loaded onto that machine's balance. */
  @IsOptional()
  @IsUUID()
  machineId?: string;

  @IsBoolean()
  withService: boolean;

  /** Agent route only. agent: agent pays amount + profit, customer gets the
   *  full amount. customer: customer gets amount - profit. The machine route
   *  is always paid by the customer. */
  @IsOptional()
  @IsIn(['agent', 'customer'])
  profitPayer?: 'agent' | 'customer';

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
