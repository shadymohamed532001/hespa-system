import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsBoolean,
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
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { ExecutionMode } from '../../database/enums.js';

export class IncomingPartDto {
  @ValidateIf((part: IncomingPartDto) => part.accountId == null)
  @IsUUID()
  walletId?: string;

  @ValidateIf((part: IncomingPartDto) => part.walletId == null)
  @IsUUID()
  accountId?: string;

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
  @IsUUID()
  purchaseVisaId?: string;

  /** Required when the execution source is a purchase visa. */
  @IsOptional()
  @IsBoolean()
  withService?: boolean;

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

  @IsOptional()
  @IsBoolean()
  useAgentCredit = false;
}
