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

  React.useEffect(() => {
    const controller = new AbortController();
    setData(undefined);
    const url = new URL(`/api/private/torii/profiles/${userId}`, 'https://lazer-api.shikkesora.com');
    url.searchParams.set('mode', mode);
    void fetch(url, { signal: controller.signal, credentials: 'omit' })
      .then(async response => {
        if (!response.ok) throw new Error('Profiles unavailable');
        return await response.json() as ProfilesResponse;
      })
      .then(result => { if (!controller.signal.aborted) setData(result); })
      .catch(() => {});
    return () => controller.abort();
  }, [userId, mode]);

  if (data == null || data.profiles.length <= 1) return null;
  const selected = data.profiles.some(profile => profile.user_id === userId) ? userId : '';
  return (
    <label className='profile-info__player-profiles'>
      <span className='fas fa-user' aria-hidden />
      <select
        aria-label='Player profile'
        onChange={event => window.location.assign(route('users.show', { user: event.target.value, mode }))}
        value={selected}
      >
        {selected === '' && <option value='' disabled>Choose profile</option>}
        {data.profiles.map(profile => <option key={profile.user_id} value={profile.user_id}>{profile.name}</option>)}
      </select>
    </label>
  );
}
