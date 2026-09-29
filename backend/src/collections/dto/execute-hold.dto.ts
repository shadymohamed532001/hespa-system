import { IsBoolean, IsNumber, IsOptional, IsUUID, Min } from 'class-validator';

export class ExecuteHoldDto {
  @IsOptional()
  @IsUUID()
  accountId?: string;

  @IsOptional()
  @IsUUID()
  purchaseVisaId?: string;

  @IsOptional()
  @IsBoolean()
  withService?: boolean;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  commission = 0;
}
