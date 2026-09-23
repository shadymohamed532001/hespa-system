import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RecoverAdminDto {
  @IsString()
  @MinLength(16)
  @MaxLength(256)
  recoveryKey: string;

  @IsString()
  @MinLength(3)
  @MaxLength(80)
  username: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  displayName?: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  password: string;
}
