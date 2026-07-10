import { Controller } from "@hotwired/stimulus"
import {
  Chart, LineController, LineElement, PointElement,
  LinearScale, CategoryScale, Tooltip, Filler
} from "chart.js"

// The "chart.js" entry (not "chart.js/auto") is tree-shakeable, so register the
// pieces a line chart needs.
Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Filler)

// Draws an RTT line chart from server-provided labels/points. Null points
// (unreachable checks) render as gaps in the line.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { labels: Array, points: Array }

  connect() {
    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [{
          label: "RTT (ms)",
          data: this.pointsValue,
          borderColor: "#3b82f6",
          backgroundColor: "rgba(59, 130, 246, 0.15)",
          fill: true,
          tension: 0.3,
          pointRadius: 0,
          spanGaps: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: { beginAtZero: true, ticks: { color: "#9fb0c0" }, grid: { color: "#2a3947" } },
          x: { ticks: { color: "#9fb0c0", maxTicksLimit: 8 }, grid: { display: false } }
        },
        plugins: { legend: { labels: { color: "#e6edf3" } } }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
