import { requireNativeModule } from 'expo-modules-core';
import type { OfficeWifiModule } from '@opsdesk/contracts';

export default requireNativeModule<OfficeWifiModule>('OpsDeskOfficeWifi');
