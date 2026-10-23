// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import "controllers"
import { application } from "controllers/application"
import "recording_studio_dropbox/dropbox_picker_launcher"

ActiveStorage.start()

