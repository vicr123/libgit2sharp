using System.Runtime.InteropServices;

namespace LibGit2Sharp.Core
{
    [StructLayout(LayoutKind.Sequential)]
    internal unsafe struct GitCredentialSshKey
    {
        public GitCredential parent;
        public char *username;
        public char *publickey;
        public char *privatekey;
        public char *passphrase;
    }
}
