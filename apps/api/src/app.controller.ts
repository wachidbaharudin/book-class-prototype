import { Controller, Get } from '@nestjs/common';
import type { HealthResponse } from '@bookclass/shared';
import { AppService } from './app.service';

@Controller('health')
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  health(): HealthResponse {
    return this.appService.health();
  }
}
