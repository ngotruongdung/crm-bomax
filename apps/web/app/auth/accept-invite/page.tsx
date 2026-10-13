import { AcceptInviteClient } from './accept-invite-client';

type AcceptInvitePageProps = {
  searchParams: Promise<{
    status?: string | string[];
    token?: string | string[];
  }>;
};

function getSingleQueryValue(value: string | string[] | undefined) {
  return typeof value === 'string' ? value.trim() : '';
}

export default async function AcceptInvitePage({ searchParams }: AcceptInvitePageProps) {
  const params = await searchParams;
  const token = getSingleQueryValue(params.token);

  return (
    <main className="auth-page auth-page-single">
      {token ? <AcceptInviteClient token={token} /> : <AcceptInviteClient token="" />}
    </main>
  );
}
