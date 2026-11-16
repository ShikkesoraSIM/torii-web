// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

import * as React from 'react';
import { route } from 'laroute';
import Ruleset from 'interfaces/ruleset';

interface ProfilesResponse {
  master_user_id: number;
  profiles: { user_id: number; name: string }[];
}

export default function PlayerProfileSelector({ userId, mode }: { userId: number; mode: Ruleset }) {
  const [data, setData] = React.useState<ProfilesResponse>();
  const [failed, setFailed] = React.useState(false);
  const [attempt, setAttempt] = React.useState(0);
  React.useEffect(() => {
    const controller = new AbortController();
    setData(undefined);
    setFailed(false);
    const url = new URL(`/api/v2/torii/profiles/${userId}`, 'https://lazer-api.shikkesora.com');
    url.searchParams.set('mode', mode);
    void fetch(url, { signal: controller.signal, credentials: 'omit' })
      .then(async response => {
        if (!response.ok) throw new Error('Profiles unavailable');
        return await response.json() as ProfilesResponse;
      })
      .then(result => { if (!controller.signal.aborted) setData(result); })
      .catch(() => { if (!controller.signal.aborted) setFailed(true); });
    return () => controller.abort();
  }, [userId, mode, attempt]);

  if (failed) return <button className='btn-osu-big btn-osu-big--text' onClick={() => setAttempt(attempt + 1)} type='button'>Retry player profiles</button>;
  if (data == null || data.profiles.length < 2 && data.master_user_id === userId) return null;
  const selected = data.profiles.some(profile => profile.user_id === userId) ? userId : '';
  return (
    <label className='profile-info__player-profiles'>
      <span className='fas fa-user' aria-hidden />
      <span>Player profile</span>
      <select
        aria-label='Player profile'
        onChange={event => window.location.assign(route('users.show', { user: event.target.value, mode }))}
        value={selected}
      >
        {selected === '' && <option value='' disabled>Choose a profile for this mode</option>}
        {data.profiles.map(profile => <option key={profile.user_id} value={profile.user_id}>{profile.name}</option>)}
      </select>
    </label>
  );
}
