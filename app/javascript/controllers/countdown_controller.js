import { Controller } from "@hotwired/stimulus"

// Counts down the seconds until the next scheduled check (the cron runs at the
// top of every minute), resetting each minute. Pure client-side behaviour.
export default class extends Controller {
  static targets = ["output"]

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    this.outputTarget.textContent = 60 - new Date().getSeconds()
  }
}
