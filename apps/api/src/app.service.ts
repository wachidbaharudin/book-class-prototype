import { Injectable } from '@nestjs/common';
import { APP_NAME } from '@bookclass/shared';

@Injectable()
export class AppService {
  health(): { status: string; app: string } {
    return { status: 'ok', app: APP_NAME };
  }
}
