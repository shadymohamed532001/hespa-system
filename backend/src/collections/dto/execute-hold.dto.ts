import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { IncomingPartDto } from './receive-collection.dto.js';

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
