import { IsObject } from 'class-validator';
import { ReversalDto } from '../common/dto/reversal.dto.js';

export class CorrectionDto extends ReversalDto {
  @IsObject()
  values: Record<string, unknown>;
}
