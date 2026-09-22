import { IsNumber, IsUUID, Min } from 'class-validator';

export class ExecuteHoldDto {
  @IsUUID()
  accountId: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  commission = 0;
}

