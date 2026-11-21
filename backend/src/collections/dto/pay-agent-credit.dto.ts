import {
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/** Cash handed back to an agent out of their deposit (always from treasury). */
export class RefundAgentCreditDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  agentName: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;
}

/**
 * Money received from an agent. Without a destination it is cash into the
 * treasury; otherwise it lands on a wallet (including InstaPay) or a QR profit
 * account.
 */
export class PayAgentCreditDto extends RefundAgentCreditDto {
  @IsOptional()
  @IsUUID()
  walletId?: string;

  @IsOptional()
  @IsUUID()
  accountId?: string;
}
