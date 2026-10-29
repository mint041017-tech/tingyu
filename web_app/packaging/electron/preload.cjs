const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('tingyuShell', {
  platform: process.platform,
  electron: process.versions.electron,
  chrome: process.versions.chrome,
  isDesktop: true,
});
