import { IsString, MaxLength, MinLength } from 'class-validator';

export class LoginDto {
  @IsString()
  @MaxLength(80)
  username: string;

  @IsString()
  @MinLength(4)
  @MaxLength(128)
  password: string;
}
