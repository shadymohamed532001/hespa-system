import { IsDateString, IsEnum, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min, MinLength } from 'class-validator';
import { ExecutionMode } from '../../database/enums.js';

export class ReceiveCollectionDto {
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  agentName: string;

  @IsString()
  @MinLength(2)
  @MaxLength(150)
  companyName: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsEnum(ExecutionMode)
  executionMode: ExecutionMode;

  @IsOptional()
  @IsDateString()
  receivedAt?: string;

  @IsOptional()
  @IsUUID()
  accountId?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  commission = 0;
}
