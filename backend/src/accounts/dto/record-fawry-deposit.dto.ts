import { Transform, Type } from 'class-transformer';
import {
  IsInt,
  IsDefined,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class FawryCashCountsDto {
  @IsInt()
  @Min(0)
  @Max(100_000)
  count200: number;

  @IsInt()
  @Min(0)
  @Max(100_000)
  count100: number;

  @IsInt()
  @Min(0)
  @Max(100_000)
  count50: number;

  @IsInt()
  @Min(0)
  @Max(100_000)
  count20: number;

  @IsInt()
  @Min(0)
  @Max(100_000)
  count10: number;

  @IsInt()
  @Min(0)
  @Max(100_000)
  count5: number;
}

export class RecordFawryDepositDto {
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  depositorName?: string;

  @IsOptional()
  @IsUUID()
  depositorUserId?: string;

  @IsDefined()
  @ValidateNested()
  @Type(() => FawryCashCountsDto)
  cashCounts: FawryCashCountsDto;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;
}
