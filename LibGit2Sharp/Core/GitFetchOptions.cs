using System.Runtime.InteropServices;

namespace LibGit2Sharp.Core
{
    [StructLayout(LayoutKind.Sequential)]
    internal class GitFetchOptions
    {
        public int Version = 1;
        public GitRemoteCallbacks RemoteCallbacks;
        public FetchPruneStrategy Prune;
        public bool UpdateFetchHead = true;
        public TagFetchMode download_tags;
        public GitProxyOptions ProxyOptions;
        public int depth = 0;
        public int FollowRedirects = 1 << 1;
        public GitStrArrayManaged CustomHeaders;
    }
}
