// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

import * as d3 from 'd3';

interface Datum {
  date: string;
  online: number | null;
  online_estimated?: boolean;
  scores: number;
}

const defaultLabels = {
  label: 'Server activity over the last 10 days',
  online: 'online peak/day',
  peak: 'Busiest day, :count scores (:date)',
  period: 'last 10 days',
  scales: 'Scores use the left scale; online players use the right scale.',
  scores: 'scores/day',
  unavailable: 'online history not recorded yet',
};

export default class LandingUserStats {
  private active = false;
  private readonly container = document.querySelector<HTMLElement>('.js-landing-graph');
  private readonly data: Datum[] = [];
  private readonly dateFormat = new Intl.DateTimeFormat(document.documentElement.lang || 'en', { day: 'numeric', month: 'short', timeZone: 'UTC' });
  private readonly labels = defaultLabels;
  private readonly numberFormat = new Intl.NumberFormat(document.documentElement.lang || 'en');
  private selected = 0;
  private readonly summary = document.createElement('p');
  private readonly svg = d3.create('svg');
  private readonly x = d3.scaleUtc();

  constructor() {
    if (this.container == null) return;

    try {
      const labels = JSON.parse(this.container.dataset.labels ?? '{}') as Partial<typeof defaultLabels>;
      this.labels = { ...defaultLabels, ...labels };
      const data = JSON.parse(document.getElementById('json-stats')?.textContent ?? '[]') as Datum[];
      this.data = data.filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d.date)
        && Number.isFinite(Date.parse(d.date))
        && new Date(d.date).toISOString().slice(0, 10) === d.date
        && Number.isFinite(d.scores) && d.scores >= 0
        && (d.online == null || (Number.isFinite(d.online) && d.online >= 0)))
        .sort((a, b) => a.date.localeCompare(b.date)).slice(-10);
    } catch {
      this.data = [];
    }

    this.container.hidden = this.data.length === 0;
    if (this.data.length === 0) return;
    this.selected = this.data.length - 1;
    this.container.classList.add('landing-graph');
    this.container.replaceChildren();

    const heading = document.createElement('div');
    heading.className = 'landing-graph__heading';
    const period = document.createElement('span');
    period.textContent = this.labels.period;
    const legend = document.createElement('div');
    legend.className = 'landing-graph__legend';
    for (const series of ['scores', 'online'] as const) {
      const item = document.createElement('span');
      const unavailable = series === 'online' && !this.hasOnline;
      item.className = `landing-graph__legend-item landing-graph__legend-item--${series}`;
      item.textContent = unavailable ? this.labels.unavailable : this.labels[series];
      item.title = unavailable ? this.labels.unavailable : this.labels.scales;
      if (unavailable) item.classList.add('landing-graph__legend-item--unavailable');
      legend.append(item);
    }
    heading.append(period, legend);
    this.summary.className = 'landing-graph__summary';
    this.container.append(heading, this.summary);
    this.svg.attr('class', 'landing-graph__plot')
      .attr('role', 'slider')
      .attr('tabindex', 0)
      .attr('aria-label', `${this.labels.label}. ${this.labels.scales}`)
      .attr('aria-orientation', 'horizontal')
      .attr('aria-valuemin', 1)
      .attr('aria-valuemax', this.data.length);
    this.container.append(this.svg.node()!);

    this.svg.on('pointermove pointerdown', (event: PointerEvent) => {
      const [position] = d3.pointer(event, this.svg.node());
      const time = this.x.invert(position).getTime();
      this.showDay(d3.leastIndex(this.data, (d) => Math.abs(Date.parse(d.date) - time)) ?? 0);
    }).on('pointerleave blur', () => {
      if (document.activeElement !== this.svg.node()) this.showPeak();
    }).on('focus', () => this.showDay(this.selected))
      .on('keydown', (event: KeyboardEvent) => {
        const navigation: Record<string, number> = { ArrowLeft: this.selected - 1, ArrowRight: this.selected + 1, End: this.data.length - 1, Home: 0 };
        const next = navigation[event.key];
        if (next == null) return;
        event.preventDefault();
        this.showDay(Math.max(0, Math.min(this.data.length - 1, next)));
      });
    this.resize();
  }

  readonly resize = () => {
    if (this.container == null || this.data.length === 0) return;
    const width = Math.max(1, this.svg.node()!.getBoundingClientRect().width);
    const height = 82;
    const bottom = 62;
    const dates = this.data.map((d) => Date.parse(d.date));
    this.x.domain([dates[0], dates[dates.length - 1]]).range([8, width - 8]);
    this.svg.attr('viewBox', `0 0 ${width} ${height}`).selectAll('*').remove();

    this.svg.append('line').attr('class', 'landing-graph__baseline')
      .attr('x1', 8).attr('x2', width - 8).attr('y1', bottom).attr('y2', bottom);

    for (const series of ['scores', 'online'] as const) {
      if (series === 'online' && !this.hasOnline) continue;
      const maximum = d3.max(this.data, (d) => d[series] ?? 0) ?? 0;
      const y = d3.scaleLinear().domain([0, Math.max(1, maximum)]).range([bottom, 14]);
      if (series === 'scores') y.nice();
      const area = d3.area<Datum>().defined((d) => d[series] != null)
        .x((d) => this.x(Date.parse(d.date))).y0(bottom).y1((d) => y(d[series] ?? 0)).curve(d3.curveMonotoneX);
      const line = d3.line<Datum>().defined((d) => d[series] != null)
        .x((d) => this.x(Date.parse(d.date))).y((d) => y(d[series] ?? 0)).curve(d3.curveMonotoneX);
      this.svg.append('path').datum(this.data).attr('class', `landing-graph__area landing-graph__area--${series}`).attr('d', area);
      this.svg.append('path').datum(this.data).attr('class', `landing-graph__line landing-graph__line--${series}`).attr('d', line);
      if (series === 'scores' && maximum > 0) {
        const peak = d3.greatest(this.data, (d) => d.scores)!;
        this.svg.append('circle').attr('class', 'landing-graph__peak').attr('r', 2.5)
          .attr('cx', this.x(Date.parse(peak.date))).attr('cy', y(peak.scores));
      }
      this.svg.append('text').attr('class', `landing-graph__axis landing-graph__axis--${series}`)
        .attr('x', series === 'scores' ? 8 : width - 8).attr('y', 9)
        .attr('text-anchor', series === 'scores' ? 'start' : 'end')
        .text(this.numberFormat.format(y.domain()[1]));
    }

    for (const index of [0, this.data.length - 1]) {
      this.svg.append('text').attr('class', 'landing-graph__date')
        .attr('x', index === 0 ? 8 : width - 8).attr('y', height - 2)
        .attr('text-anchor', index === 0 ? 'start' : 'end').text(this.formatDate(this.data[index].date));
    }
    this.svg.append('line').attr('class', 'landing-graph__cursor')
      .attr('y1', 12).attr('y2', bottom).attr('visibility', 'hidden');
    this.showPeak();
    this.svg.attr('aria-valuenow', this.selected + 1).attr('aria-valuetext', this.dayText(this.data[this.selected]));
    if (document.activeElement === this.svg.node()) this.showDay(this.selected);
  };

  private get hasOnline() {
    return this.data.some((d) => d.online != null);
  }

  private dayText(day: Datum) {
    const online = day.online == null ? this.labels.unavailable : `${this.numberFormat.format(day.online)} ${this.labels.online}`;
    return `${this.formatDate(day.date)}: ${this.numberFormat.format(day.scores)} ${this.labels.scores} / ${online}`;
  }

  private formatDate(date: string) {
    return this.dateFormat.format(new Date(`${date}T00:00:00Z`));
  }

  private showDay(index: number) {
    if (this.active && index === this.selected) return;
    this.active = true;
    this.selected = index;
    const day = this.data[index];
    const text = this.dayText(day);
    this.summary.textContent = text;
    this.svg.select('.landing-graph__cursor').attr('visibility', 'visible')
      .attr('x1', this.x(Date.parse(day.date))).attr('x2', this.x(Date.parse(day.date)));
    this.svg.attr('aria-valuenow', index + 1).attr('aria-valuetext', text);
  }

  private showPeak() {
    this.active = false;
    const peak = d3.greatest(this.data, (d) => d.scores)!;
    this.summary.textContent = this.labels.peak.replace(':count', this.numberFormat.format(peak.scores)).replace(':date', this.formatDate(peak.date));
    this.svg.select('.landing-graph__cursor').attr('visibility', 'hidden');
  }
}
