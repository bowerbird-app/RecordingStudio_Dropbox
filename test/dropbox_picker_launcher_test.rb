# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "tmpdir"

class DropboxPickerLauncherTest < Minitest::Test
  def test_dropbox_launcher_prefetches_and_chooses_inside_a_click
    launcher_source = File.read(dropbox_launcher_path)

    assert_includes launcher_source, 'from "recording_studio_attachable/provider_launchers"'
    assert_includes launcher_source, "loadScript"
    assert_includes launcher_source, "createBootstrapCache"
    assert_includes launcher_source, "providerNeedsAuth"
    assert_includes launcher_source, "openProviderAuth"
    assert_includes launcher_source, "csrfToken"
    assert_includes launcher_source, "if (gesture && canOpenNow(session))"
    assert_includes launcher_source, "window.Dropbox.choose"
    refute_includes launcher_source, "showProviderContinueButton"
    refute_includes launcher_source, "Choose from Dropbox"
    refute_includes launcher_source, "oauth_connect_url"

    skip "node is not available" unless node_available?
    skip "recording_studio_attachable is not in this bundle" unless provider_launchers_source

    stdout, stderr, status = run_node_launcher_harness
    assert status.success?, "#{stderr}\n#{stdout}"
    result = JSON.parse(stdout)
    assert_equal true, result.fetch("chooseOnReadyClick")
    assert_equal true, result.fetch("chooserSendsFilename")
    assert_equal true, result.fetch("prefetchAwaitsChooser")
    assert_equal true, result.fetch("marikitClick1OpenedChooser")
    assert_equal 0, result.fetch("marikitClick1OpenedPopup")
    refute result.fetch("marikitClick1ShowedWarming")
    assert_equal true, result.fetch("chooseOnColdClick")
    assert_equal 0, result.fetch("popupOnColdClick")
    assert_equal true, result.fetch("popupOnReadyAuthClick")
    assert_equal true, result.fetch("postedOauthConnectIntoPopup")
    assert_equal 0, result.fetch("chooseAfterConnectWithoutClick")
    assert_equal true, result.fetch("chooseAfterConnectOnSamePage")
    assert_equal 0, result.fetch("popupAfterConnectOnSamePage")
    assert_equal 2, result.fetch("bootstrapsAfterRelaunch")
    assert_equal true, result.fetch("forbiddenPrefetchHandled")
    assert_equal true, result.fetch("forbiddenButtonDisabled")
    assert_equal false, result.fetch("forbiddenPrefetchAnnounced")
    assert_equal 0, result.fetch("unhandledRejections")
    assert_equal true, result.fetch("blockedPopupRejected")
  end

  private

  def dropbox_launcher_path
    File.expand_path("../app/javascript/recording_studio_dropbox/dropbox_picker_launcher.js", __dir__)
  end

  def provider_launchers_path
    spec = Gem.loaded_specs["recording_studio_attachable"]
    return unless spec

    File.join(spec.full_gem_path, "app/javascript/controllers/recording_studio_attachable/provider_launchers.js")
  end

  def dropbox_launcher_under_test
    ENV.fetch("DROPBOX_LAUNCHER_PATH", dropbox_launcher_path)
  end

  def provider_launchers_source
    path = provider_launchers_path
    if path && File.exist?(path)
      source = File.read(path)
      return source if source.include?("createBootstrapCache")
    end

    fallback = File.expand_path("/tmp/provider_launchers_head.js")
    if File.exist?(fallback)
      cached = File.read(fallback)
      return cached if cached.include?("createBootstrapCache")
    end

    require "net/http"
    require "uri"
    uri = URI(
      "https://raw.githubusercontent.com/bowerbird-app/RecordingStudio_attachable/" \
      "main/app/javascript/controllers/recording_studio_attachable/provider_launchers.js"
    )
    fetched = Net::HTTP.get(uri)
    File.write(fallback, fetched) if fetched.include?("createBootstrapCache")
    fetched
  end

  def node_available?
    system("node", "-v", out: File::NULL, err: File::NULL)
  end

  def run_node_launcher_harness
    Dir.mktmpdir("dropbox-launcher-test") do |dir|
      launchers = provider_launchers_source
      unless launchers&.include?("createBootstrapCache")
        raise "Attachable provider_launchers.js is missing createBootstrapCache"
      end

      File.write(
        File.join(dir, "provider_launchers.js"),
        browser_globals_prefix + launchers
      )
      File.write(
        File.join(dir, "dropbox_picker_launcher.js"),
        browser_globals_prefix + File.read(dropbox_launcher_under_test).sub(
          'from "recording_studio_attachable/provider_launchers"',
          'from "./provider_launchers.js"'
        )
      )
      File.write(File.join(dir, "harness.mjs"), node_harness_source)
      Open3.capture3("node", File.join(dir, "harness.mjs"))
    end
  end

  def browser_globals_prefix
    "const window = globalThis;\nconst document = globalThis.document;\n"
  end

  def node_harness_source
    <<~JS
      const chooseCalls = []
      const popupCalls = []
      const formPosts = []
      const selectionNames = []
      const scripts = []

      function element(tag = "div") {
        return {
          tagName: tag.toUpperCase(),
          dataset: {},
          className: "",
          textContent: "",
          children: [],
          attributes: {},
          disabled: false,
          setAttribute(name, value) {
            this.attributes[name] = value
            if (name === "data-app-key") this.dataset.appKey = value
          },
          getAttribute(name) {
            return this.attributes[name]
          },
          querySelector() { return null },
          appendChild(child) { this.children.push(child); return child },
          replaceChildren(...nodes) { this.children = nodes }
        }
      }

      const dropboxButton = element("button")
      dropboxButton.dataset.providerLauncher = "dropbox"
      dropboxButton.dataset.dropboxAppKey = "app-key"

      const head = {
        appendChild(script) {
          scripts.push(script)
          queueMicrotask(() => {
            script.dataset.loaded = "true"
            globalThis.window.Dropbox = {
              choose(options) {
                chooseCalls.push(options)
                options.success([{ id: "id:fia-1", name: "kiln.jpg" }])
              }
            }
            script._load?.()
          })
          return script
        }
      }

      globalThis.document = {
        querySelector(sel) {
          if (sel === "[data-provider-launcher='dropbox']") return dropboxButton
          const srcMatch = String(sel).match(/^script\\[src='(.+)'\\]$/)
          if (srcMatch) return scripts.find((script) => script.src === srcMatch[1]) || null
          return null
        },
        createElement(tag) {
          const node = element(tag)
          node.type = ""
          node.name = ""
          node.value = ""
          node.method = ""
          node.action = ""
          node.target = ""
          node.submit = function() {
            const fields = {}
            this.children.forEach((child) => {
              if (child.name) fields[child.name] = child.value
            })
            formPosts.push({ action: this.action, method: this.method, target: this.target, fields })
          }
          node.remove = function() {}
          node.addEventListener = (type, fn) => {
            if (type === "load") node._load = fn
            if (type === "error") node._error = fn
          }
          return node
        },
        head,
        body: { appendChild(child) { return child } }
      }
      globalThis.window = globalThis

      const { getUploadProviderLauncher, relaunchUploadProvider } = await import("./provider_launchers.js")
      await import("./dropbox_picker_launcher.js")
      const launcher = getUploadProviderLauncher("dropbox")

      function pickerButton() {
        const button = element("button")
        button.dataset.providerKey = "dropbox"
        button.dataset.providerLauncher = "dropbox"
        button.dataset.dropboxAppKey = "app-key"
        return button
      }

      function controller() {
        const instance = {
          element: element(),
          providerButtonsByKey: new Map(),
          fetchProviderBootstrap: async () => ({ client_id: "app-key", provider_key: "dropbox" }),
          openPopup: (url) => {
            const popup = { closed: false, focus() {}, close() { this.closed = true } }
            popupCalls.push(url)
            queueMicrotask(() => popup.close())
            return popup
          },
          statuses: [],
          setProviderStatus(message) { instance.statuses.push(message) },
          clearProviderStatus() {},
          addProviderSelections(_key, selections) { selectionNames.push(...selections.map((item) => item.name)) },
          launchClientPicker(button, { gesture = false } = {}) {
            return launcher.launch({
              controller: instance,
              providerKey: button.dataset.providerKey,
              bootstrapUrl: button.dataset.providerBootstrapUrl,
              button,
              gesture
            })
          }
        }
        return instance
      }

      let resolveMarikitBootstrap
      const marikitController = controller()
      const marikitButton = pickerButton()
      marikitButton.dataset.providerBootstrapUrl = "/dropbox/marikit"
      marikitController.providerButtonsByKey.set("dropbox", marikitButton)
      marikitController.fetchProviderBootstrap = () => new Promise((resolve) => {
        resolveMarikitBootstrap = () => resolve({
          client_id: "app-key",
          needs_auth: true,
          reconnect: true,
          connect: {
            url: "/recording_studio_oauth/outbound/dropbox/connect",
            method: "post",
            fields: {
              authenticity_token: "csrf-token",
              owner: "user",
              return_to: "/dropbox/recordings/rec-1/connected?popup=1"
            }
          }
        })
      })
      launcher.prefetch({
        controller: marikitController,
        bootstrapUrl: "/dropbox/marikit",
        button: marikitButton
      })
      await new Promise((resolve) => queueMicrotask(resolve))
      chooseCalls.length = 0
      popupCalls.length = 0
      marikitController.statuses = []
      const marikitClick1Launch = launcher.launch({
        controller: marikitController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/marikit",
        button: marikitButton,
        gesture: true
      })
      const marikitClick1OpenedChooser = chooseCalls.length === 1
      const marikitClick1OpenedPopup = popupCalls.length
      const marikitClick1ShowedWarming = marikitController.statuses.includes("Dropbox is warming up…")
      const chooseOnColdClick = marikitClick1OpenedChooser
      const popupOnColdClick = marikitClick1OpenedPopup
      resolveMarikitBootstrap()
      await marikitClick1Launch
      await new Promise((resolve) => queueMicrotask(resolve))
      chooseCalls.length = 0
      popupCalls.length = 0
      await launcher.launch({
        controller: marikitController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/marikit",
        button: marikitButton,
        gesture: true
      })
      const marikitClick2OpenedChooser = chooseCalls.length
      const marikitClick2OpenedPopup = popupCalls.length
      await new Promise((resolve) => queueMicrotask(resolve))
      const closedFlashPopup = popupCalls.length > 0
      marikitController.fetchProviderBootstrap = async () => ({ client_id: "app-key", provider_key: "dropbox" })
      await Promise.resolve(relaunchUploadProvider(marikitController, "dropbox"))
      await new Promise((resolve) => queueMicrotask(resolve))
      chooseCalls.length = 0
      popupCalls.length = 0
      await launcher.launch({
        controller: marikitController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/marikit",
        button: marikitButton,
        gesture: true
      })
      const marikitClick3OpenedChooser = chooseCalls.length === 1

      const readyController = controller()
      const readyButton = pickerButton()
      readyButton.dataset.providerBootstrapUrl = "/dropbox/ready"
      await launcher.prefetch({
        controller: readyController,
        bootstrapUrl: "/dropbox/ready",
        button: readyButton
      })
      const prefetchAwaitsChooser = typeof globalThis.window.Dropbox?.choose === "function"
      chooseCalls.length = 0
      await launcher.launch({
        controller: readyController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/ready",
        button: readyButton,
        gesture: true
      })
      const chooseOnReadyClick = chooseCalls.length === 1
      const chooserSendsFilename = selectionNames.includes("kiln.jpg")

      const authController = controller()
      authController.fetchProviderBootstrap = async () => ({
        client_id: "app-key",
        needs_auth: true,
        connect: {
          url: "/recording_studio_oauth/outbound/dropbox/connect",
          method: "post",
          fields: {
            authenticity_token: "csrf-token",
            owner: "user",
            return_to: "/dropbox/recordings/rec-1/connected?popup=1"
          }
        }
      })
      await launcher.prefetch({ controller: authController, bootstrapUrl: "/dropbox/auth" })
      popupCalls.length = 0
      formPosts.length = 0
      await launcher.launch({
        controller: authController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/auth",
        gesture: true
      })
      const popupOnReadyAuthClick = popupCalls[0] === "about:blank"
      const postedOauthConnectIntoPopup = formPosts[0]?.action === "/recording_studio_oauth/outbound/dropbox/connect" &&
        formPosts[0]?.target === "dropbox-auth" &&
        formPosts[0]?.fields?.owner === "user" &&
        formPosts[0]?.fields?.return_to?.includes("/dropbox/recordings/rec-1/connected") &&
        formPosts[0]?.fields?.authenticity_token === "csrf-token"

      const connectThenChooseController = controller()
      const connectThenChooseButton = pickerButton()
      connectThenChooseButton.dataset.providerBootstrapUrl = "/dropbox/connect-then-choose"
      connectThenChooseController.providerButtonsByKey.set("dropbox", connectThenChooseButton)
      let connectThenChooseBootstraps = 0
      connectThenChooseController.fetchProviderBootstrap = async () => {
        connectThenChooseBootstraps += 1
        if (connectThenChooseBootstraps === 1) {
          return {
            client_id: "app-key",
            needs_auth: true,
            connect: {
              url: "/recording_studio_oauth/outbound/dropbox/connect",
              method: "post",
              fields: {
                authenticity_token: "csrf-token",
                owner: "user",
                return_to: "/dropbox/recordings/rec-1/connected?popup=1"
              }
            }
          }
        }
        return { client_id: "app-key", provider_key: "dropbox" }
      }
      await launcher.prefetch({
        controller: connectThenChooseController,
        bootstrapUrl: "/dropbox/connect-then-choose",
        button: connectThenChooseButton
      })
      popupCalls.length = 0
      chooseCalls.length = 0
      await launcher.launch({
        controller: connectThenChooseController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/connect-then-choose",
        button: connectThenChooseButton,
        gesture: true
      })
      popupCalls.length = 0
      chooseCalls.length = 0
      await Promise.all([
        relaunchUploadProvider(connectThenChooseController, "dropbox"),
        relaunchUploadProvider(connectThenChooseController, "dropbox")
      ])
      await new Promise((resolve) => queueMicrotask(resolve))
      const chooseAfterConnectWithoutClick = chooseCalls.length
      const popupAfterConnectOnSamePage = popupCalls.length
      const bootstrapsAfterRelaunch = connectThenChooseBootstraps
      await launcher.launch({
        controller: connectThenChooseController,
        providerKey: "dropbox",
        bootstrapUrl: "/dropbox/connect-then-choose",
        button: connectThenChooseButton,
        gesture: true
      })
      const chooseAfterConnectOnSamePage = chooseCalls.length === 1

      const forbiddenButton = element("button")
      forbiddenButton.disabled = false
      const forbiddenController = controller()
      forbiddenController.handleProviderBootstrapError = (error, button, { announce = true } = {}) => {
        if (button && error?.status === 403) button.disabled = true
        forbiddenController._bootstrapError = error
        forbiddenController._announced = announce
      }
      forbiddenController.fetchProviderBootstrap = async () => {
        const error = new Error("Forbidden")
        error.status = 403
        throw error
      }
      const unhandled = []
      const onUnhandled = (reason) => unhandled.push(String(reason))
      process.on("unhandledRejection", onUnhandled)
      await launcher.prefetch({
        controller: forbiddenController,
        bootstrapUrl: "/dropbox/forbidden",
        button: forbiddenButton
      })
      await new Promise((resolve) => setTimeout(resolve, 0))
      process.off("unhandledRejection", onUnhandled)
      const forbiddenPrefetchHandled = forbiddenController._bootstrapError?.status === 403
      const forbiddenButtonDisabled = forbiddenButton.disabled === true
      const forbiddenPrefetchAnnounced = forbiddenController._announced

      const blockedController = controller()
      blockedController.openPopup = () => null
      blockedController.fetchProviderBootstrap = async () => ({
        client_id: "app-key",
        needs_auth: true,
        connect: {
          url: "/recording_studio_oauth/outbound/dropbox/connect",
          method: "post",
          fields: { authenticity_token: "csrf-token" }
        }
      })
      await launcher.prefetch({ controller: blockedController, bootstrapUrl: "/dropbox/blocked" })
      let blockedPopupMessage = null
      try {
        await launcher.launch({
          controller: blockedController,
          providerKey: "dropbox",
          bootstrapUrl: "/dropbox/blocked",
          gesture: true
        })
      } catch (error) {
        blockedPopupMessage = error.message
      }
      const blockedPopupRejected = blockedPopupMessage === "The sign-in popup was blocked. Allow popups and try again."

      process.stdout.write(JSON.stringify({
        chooseOnReadyClick,
        chooserSendsFilename,
        prefetchAwaitsChooser,
        marikitClick1OpenedChooser,
        marikitClick1OpenedPopup,
        marikitClick1ShowedWarming,
        marikitClick2OpenedChooser,
        marikitClick2OpenedPopup,
        marikitClick3OpenedChooser,
        closedFlashPopup,
        chooseOnColdClick,
        popupOnColdClick,
        popupOnReadyAuthClick,
        postedOauthConnectIntoPopup,
        chooseAfterConnectWithoutClick,
        chooseAfterConnectOnSamePage,
        popupAfterConnectOnSamePage,
        bootstrapsAfterRelaunch,
        forbiddenPrefetchHandled,
        forbiddenButtonDisabled,
        forbiddenPrefetchAnnounced,
        unhandledRejections: unhandled.length,
        blockedPopupRejected
      }))
    JS
  end
end
