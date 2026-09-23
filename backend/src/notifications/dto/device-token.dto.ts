import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(20)
  @MaxLength(512)
  token: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  platform?: string;
}

export class UnregisterDeviceTokenDto {
  @IsString()
  @MinLength(20)
  @MaxLength(512)
  token: string;
}
