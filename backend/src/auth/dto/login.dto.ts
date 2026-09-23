import { IsEnum, IsString, MaxLength, MinLength } from 'class-validator';

export enum LoginPortal {
  ADMIN = 'admin',
  EMPLOYEE = 'employee',
}

export class LoginDto {
  @IsString()
  @MaxLength(80)
  username: string;

  @IsString()
  @MinLength(4)
  @MaxLength(128)
  password: string;

  /** Which entrance the client is using — must match the account role. */
  @IsEnum(LoginPortal)
  portal: LoginPortal;
}
