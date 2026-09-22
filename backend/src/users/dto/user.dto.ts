import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { AppPermission, UserRole } from '../../database/enums.js';

export class UserLimitsDto {
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  maxReceiveAmount?: number | null;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  maxTopUpAmount?: number | null;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  maxSaleAmount?: number | null;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  maxTransferAmount?: number | null;
}

export class CreateUserDto {
  @IsString()
  @MinLength(3)
  @MaxLength(80)
  username: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  password: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  displayName?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsArray()
  @IsEnum(AppPermission, { each: true })
  permissions?: AppPermission[];

  @IsOptional()
  @ValidateNested()
  @Type(() => UserLimitsDto)
  limits?: UserLimitsDto;
}

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  password?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsArray()
  @IsEnum(AppPermission, { each: true })
  permissions?: AppPermission[];

  @IsOptional()
  @ValidateNested()
  @Type(() => UserLimitsDto)
  limits?: UserLimitsDto;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
