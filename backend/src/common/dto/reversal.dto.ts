import { IsString, MaxLength, MinLength } from 'class-validator';

export class ReversalDto {
  @IsString()
  @MinLength(3)
  @MaxLength(300)
  reason: string;
}
