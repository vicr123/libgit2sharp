using System;
using LibGit2Sharp.Core;

namespace LibGit2Sharp
{
    /// <summary>
    /// Class that holds SSH key credentials for remote repository access.
    /// </summary>
    public sealed class SshKeyCredentials : Credentials
    {
        protected internal override int GitCredentialHandler(out IntPtr cred)
        {
            if (Username == null || PublicKey == null || PrivateKey == null)
            {
                throw new InvalidOperationException("SshKeyCredentials contains a null Username, PublicKey or PrivateKey.");
            }

            return NativeMethods.git_cred_ssh_key_new(out cred, Username, PublicKey, PrivateKey, Passphrase);
        }

        static internal unsafe SshKeyCredentials FromNative(GitCredentialSshKey* gitCred)
        {
            return new SshKeyCredentials()
            {
                Username = LaxUtf8Marshaler.FromNative(gitCred->username),
                PublicKey = LaxUtf8Marshaler.FromNative(gitCred->publickey),
                PrivateKey = LaxUtf8Marshaler.FromNative(gitCred->privatekey),
                Passphrase = LaxUtf8Marshaler.FromNative(gitCred->privatekey)
            };
        }

        /// <summary>
        /// Username to authenticate as
        /// </summary>
        public string Username { get; set; }

        /// <summary>
        /// Path to a public key
        /// </summary>
        public string PublicKey { get; set; }

        /// <summary>
        /// Path to a private key
        /// </summary>
        public string PrivateKey { get; set; }

        /// <summary>
        /// Passphrase to unlock a private key
        /// </summary>
        public string Passphrase { get; set; }
    }
}
