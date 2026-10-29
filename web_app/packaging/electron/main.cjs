const { app, BrowserWindow, Menu, protocol, session, shell } = require('electron');
const fs = require('node:fs/promises');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', 'www');
const APP_ORIGIN = 'app://tingyu';
const IS_SMOKE = process.argv.includes('--smoke');
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.map': 'application/json; charset=utf-8',
};

protocol.registerSchemesAsPrivileged([
  {
    scheme: 'app',
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      corsEnabled: true,
      stream: true,
    },
  },
]);

app.setName('听隅');
app.setAppUserModelId('com.citro.tingyu');
app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');
app.commandLine.appendSwitch('enable-features', 'OverlayScrollbar');

let mainWindow = null;
let splashWindow = null;
let smokeTimer = null;

function registerProtocol() {
  protocol.handle('app', async request => {
    try {
      const url = new URL(request.url);
      let pathname = decodeURIComponent(url.pathname);
      if (pathname.endsWith('/')) pathname += 'index.html';
      const filePath = path.normalize(path.join(ROOT, pathname));
      if (!filePath.startsWith(path.normalize(ROOT))) {
        return new Response('Forbidden', { status: 403 });
      }
      const body = await fs.readFile(filePath);
      const type = MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
      return new Response(body, {
        status: 200,
        headers: {
          'content-type': type,
          'cache-control': 'no-cache',
          'access-control-allow-origin': '*',
        },
      });
    } catch (_) {
      return new Response('Not found', {
        status: 404,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }
  });
}

function buildMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac
      ? [{
          label: '听隅',
          submenu: [
            { role: 'about', label: '关于听隅' },
            { type: 'separator' },
            { role: 'hide', label: '隐藏听隅' },
            { role: 'hideOthers', label: '隐藏其他' },
            { role: 'unhide', label: '显示全部' },
            { type: 'separator' },
            { role: 'quit', label: '退出听隅' },
          ],
        }]
      : []),
    {
      label: '文件',
      submenu: [isMac ? { role: 'close', label: '关闭窗口' } : { role: 'quit', label: '退出' }],
    },
    {
      label: '显示',
      submenu: [
        { role: 'reload', label: '重新加载' },
        { type: 'separator' },
        { role: 'resetZoom', label: '实际大小' },
        { role: 'zoomIn', label: '放大' },
        { role: 'zoomOut', label: '缩小' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: '全屏' },
        ...(IS_SMOKE ? [] : [{ role: 'toggleDevTools', label: '开发者工具' }]),
      ],
    },
    {
      label: '帮助',
      submenu: [
        {
          label: '关于听隅',
          click: () => {
            const win = BrowserWindow.getFocusedWindow() || mainWindow;
            if (win) win.webContents.send('tingyu:about');
          },
        },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function createSplash() {
  splashWindow = new BrowserWindow({
    width: 430,
    height: 330,
    frame: false,
    resizable: false,
    movable: true,
    show: false,
    skipTaskbar: true,
    backgroundColor: '#223027',
    webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true },
  });
  splashWindow.loadFile(path.join(__dirname, 'splash.html'));
  splashWindow.once('ready-to-show', () => splashWindow && splashWindow.show());
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 860,
    minWidth: 820,
    minHeight: 620,
    show: false,
    title: '听隅',
    backgroundColor: '#f7f4ed',
    icon: path.join(__dirname, '..', 'resources', 'icon.png'),
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
      backgroundThrottling: false,
    },
  });

  mainWindow.setMenuBarVisibility(false);

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//i.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith(`${APP_ORIGIN}/`)) {
      event.preventDefault();
      if (/^https?:\/\//i.test(url)) shell.openExternal(url);
    }
  });

  let shown = false;
  const showMain = () => {
    if (shown || !mainWindow) return;
    shown = true;
    const delay = IS_SMOKE ? 300 : 1050;
    setTimeout(() => {
      if (!mainWindow || mainWindow.isDestroyed()) return;
      if (splashWindow && !splashWindow.isDestroyed()) splashWindow.close();
      splashWindow = null;
      mainWindow.show();
      mainWindow.focus();
      if (IS_SMOKE) runSmoke();
    }, delay);
  };

  mainWindow.once('ready-to-show', showMain);
  mainWindow.webContents.on('did-fail-load', (_event, code, description) => {
    console.error('page load failed', code, description);
    showMain();
  });

  mainWindow.loadURL(`${APP_ORIGIN}/index.html`);
  mainWindow.on('closed', () => {
    mainWindow = null;
    if (smokeTimer) clearTimeout(smokeTimer);
  });
}

async function runSmoke() {
  smokeTimer = setTimeout(async () => {
    try {
      const out = process.env.TINGYU_SMOKE_DIR
        ? path.resolve(process.env.TINGYU_SMOKE_DIR)
        : app.isPackaged
        ? path.join(app.getPath('userData'), 'smoke')
        : path.join(__dirname, '..', 'dist');
      await fs.mkdir(out, { recursive: true });
      await new Promise(resolve => setTimeout(resolve, 4200));
      const state = await mainWindow.webContents.executeJavaScript(`(() => ({
        title: document.title,
        hasSemantics: !!document.querySelector('flt-semantics'),
        hasFlutterView: !!document.querySelector('flt-glass-pane') || !!document.querySelector('flt-scene-host'),
        audioBridge: typeof tingyuCommand === 'function',
        buttons: [...document.querySelectorAll('flt-semantics [role="button"]')].map(e => e.textContent.trim()).filter(Boolean).slice(0, 20),
        viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio }
      }))()`);
      const image = await mainWindow.webContents.capturePage();
      await fs.writeFile(path.join(out, 'windows-smoke.png'), image.toPNG());
      await fs.writeFile(
        path.join(out, 'windows-smoke.json'),
        JSON.stringify({ at: new Date().toISOString(), ...state }, null, 2),
        'utf8',
      );
      console.log('SMOKE_OK', JSON.stringify(state));
      app.exit(0);
    } catch (error) {
      console.error('SMOKE_FAIL', error);
      app.exit(1);
    }
  }, 500);
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });

  app.whenReady().then(() => {
    registerProtocol();
    buildMenu();
    const ses = session.defaultSession;
    ses.setPermissionRequestHandler((_wc, permission, callback) => {
      callback(permission === 'notifications');
    });
    ses.setPermissionCheckHandler((_wc, permission) => permission === 'notifications');
    ses.setSpellCheckerEnabled(false);

    if (!IS_SMOKE) createSplash();
    createMainWindow();
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  });

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });
}
