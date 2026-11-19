import { login } from '../actions';
import { ActionForm, Submit } from '../ui';

export default function Login() {
  return (
    <div className="card login">
      <h1>🔒 Lanka Jobs</h1>
      <p className="sub">Enter your password to continue.</p>
      <ActionForm action={login}>
        <input name="password" type="password" placeholder="Password" autoFocus required />
        <div style={{ marginTop: 10 }}>
          <Submit pending="…">Log in</Submit>
        </div>
      </ActionForm>
    </div>
  );
}
