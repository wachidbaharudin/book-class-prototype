import { Injectable } from '@nestjs/common';
import { APP_NAME, HealthResponseSchema, type HealthResponse } from '@bookclass/shared';

@Injectable()
export class AppService {
  health(): HealthResponse {
    return HealthResponseSchema.parse({ status: 'ok', app: APP_NAME });
  }
}
