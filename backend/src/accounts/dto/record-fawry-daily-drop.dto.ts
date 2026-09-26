import { IsNumber, Min } from 'class-validator';

export class RecordFawryDailyDropDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount: number;
}
