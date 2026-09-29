import { IsNumber, IsString, MaxLength, Min, MinLength } from 'class-validator';

export class PayAgentCreditDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  agentName: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;
}
