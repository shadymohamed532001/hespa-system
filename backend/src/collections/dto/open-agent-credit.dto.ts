import { Transform } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class OpenAgentCreditDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  agentName: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  /** owes = the agent owes us (credit); owed = we hold the agent's money (deposit). */
  @IsOptional()
  @IsIn(['owes', 'owed'])
  direction?: 'owes' | 'owed';
}
