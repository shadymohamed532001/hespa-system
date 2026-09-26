import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ExecutionMode } from '../../database/enums.js';

export class IncomingPartDto {
  @IsUUID()
  walletId: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;
}

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

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  cashAmount?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => IncomingPartDto)
  incomingParts?: IncomingPartDto[];
}
