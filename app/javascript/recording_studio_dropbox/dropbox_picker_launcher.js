import {
  createBootstrapCache,
  csrfToken,
  hideProviderContinueButton,
  loadScript,
  openProviderAuth,
  providerNeedsAuth,
  registerUploadProviderLauncher,
  showProviderContinueButton
} from "recording_studio_attachable/provider_launchers"

const CHOOSER_SRC = "https://www.dropbox.com/static/api/2/dropins.js"
const sessions = createBootstrapCache()
let chooserPromise

function chooserAppKeyFrom(button) {
  return button?.dataset?.dropboxAppKey
}

function ensureChooserScript(appKey) {
  let script = document.querySelector(`script[src='${CHOOSER_SRC}']`)
  if (!script) {
    script = document.createElement("script")
    script.src = CHOOSER_SRC
    script.id = "dropboxjs"
    script.async = true
    script.defer = true
    if (appKey) script.setAttribute("data-app-key", appKey)
    document.head.appendChild(script)
  } else if (appKey && !script.getAttribute("data-app-key")) {
    script.setAttribute("data-app-key", appKey)
  }
}

function ensureDropboxChooserLoaded(appKey) {
  if (!chooserPromise) {
    ensureChooserScript(appKey)
    chooserPromise = loadScript(CHOOSER_SRC).then(() => {
      if (!window.Dropbox?.choose) {
        throw new Error("Dropbox Chooser did not load.")
      }
    })
  } else if (appKey) {
    ensureChooserScript(appKey)
  }

  return chooserPromise
}

function prefetchChooser(button) {
  const appKey = chooserAppKeyFrom(button)
  if (appKey) ensureDropboxChooserLoaded(appKey)
}

function openChooser() {
  return new Promise((resolve, reject) => {
    if (!window.Dropbox?.choose) {
      reject(new Error("Dropbox Chooser is not available."))
      return
    }

    window.Dropbox.choose({
      success: (files) => {
        resolve(
          (files || [])
            .filter((file) => file?.id)
            .map((file) => ({
              id: file.id,
              name: file.name
            }))
        )
      },
      cancel: () => resolve([]),
      linkType: "preview",
      multiselect: true,
      folderselect: false
    })
  })
}

function startSession(controller, bootstrapUrl) {
  return sessions.sessionFor(bootstrapUrl, async () => {
    const bootstrap = await controller.fetchProviderBootstrap(bootstrapUrl)
    if (bootstrap.client_id) {
      const chooser = ensureDropboxChooserLoaded(bootstrap.client_id)
      if (!providerNeedsAuth(bootstrap)) await chooser
    }
    return bootstrap
  })
}

function canOpenNow(session) {
  if (!session?.ready || session.error || !session.bootstrap) return false
  if (providerNeedsAuth(session.bootstrap)) return true

  return Boolean(window.Dropbox?.choose)
}

async function applySelections(controller, providerKey, selections) {
  if (selections.length === 0) {
    controller.clearProviderStatus()
    return
  }

  controller.clearProviderStatus()
  controller.addProviderSelections(providerKey, selections)
}

function openChooserNow(controller, providerKey) {
  hideProviderContinueButton(controller)
  controller.setProviderStatus("Opening Dropbox…")
  return openChooser().then((selections) => applySelections(controller, providerKey, selections))
}

function openWithGesture(controller, providerKey, bootstrap, bootstrapUrl) {
  if (providerNeedsAuth(bootstrap)) {
    csrfToken(controller, bootstrap)
    openProviderAuth(controller, bootstrap, providerKey)
    return
  }

  return openChooserNow(controller, providerKey)
}

function waitForSession(controller, session, bootstrapUrl, button) {
  controller.setProviderStatus("Dropbox is warming up…")

  return session.promise.then(() => {
    controller.clearProviderStatus()
    if (session.error) throw session.error
    return null
  }).catch((error) => {
    sessions.forget(bootstrapUrl)
    controller.handleProviderBootstrapError?.(error, button)
    throw error
  })
}

function continueAfterAuth(controller, providerKey, bootstrapUrl, button, session) {
  if (providerNeedsAuth(session.bootstrap)) return

  showProviderContinueButton(controller, button, "Open Dropbox", () => {
    openChooserNow(controller, providerKey)
  })
}

registerUploadProviderLauncher("dropbox", {
  forget(bootstrapUrl) {
    sessions.forget(bootstrapUrl)
  },

  prefetch({ controller, bootstrapUrl, button }) {
    if (!controller || !bootstrapUrl) return Promise.resolve()

    prefetchChooser(button)
    return startSession(controller, bootstrapUrl).promise.catch((error) => {
      sessions.forget(bootstrapUrl)
      controller.handleProviderBootstrapError?.(error, button, { announce: false })
    })
  },

  launch({ controller, providerKey, bootstrapUrl, button, gesture = false }) {
    prefetchChooser(button)
    hideProviderContinueButton(controller)
    const session = startSession(controller, bootstrapUrl)
    if (gesture && canOpenNow(session)) {
      return openWithGesture(controller, providerKey, session.bootstrap, bootstrapUrl)
    }
    if (gesture) {
      return waitForSession(controller, session, bootstrapUrl, button)
    }

    return session.promise.then(() => {
      if (session.error) throw session.error
      continueAfterAuth(controller, providerKey, bootstrapUrl, button, session)
    }).catch((error) => {
      sessions.forget(bootstrapUrl)
      controller.handleProviderBootstrapError?.(error, button)
      throw error
    })
  }
})
