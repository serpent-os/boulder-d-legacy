module moss.container.overlay;

import core.sys.posix.unistd : _chown = chown;
import std.file : SpanMode, dirEntries, mkdirRecurse;
import std.string : toStringz;

import moss.core.mounts;

struct OverlayFS
{
    string baseDir;
    string overlayedDir;

    string mergedDir() const pure @property
    {
        return this.joinPath(this.baseDir, this.relMergedDir);
    }

    void mount() const
    {
        foreach (ref path; [this.upperDir(), this.workDir(), this.mergedDir()])
        {
            mkdirRecurse(path);
        }
        auto prop = [
            "lowerdir": FSConfigValue(
                FSCONFIG.SET_PATH,
                cast(void*) this.overlayedDir.toStringz(),
                AT.FDCWD),
            "upperdir": FSConfigValue(
                FSCONFIG.SET_PATH,
                cast(void*) this.upperDir().toStringz(),
                AT.FDCWD),
            "workdir": FSConfigValue(
                FSCONFIG.SET_PATH,
                cast(void*) this.workDir().toStringz(),
                AT.FDCWD),
            "metacopy": FSConfigValue(FSCONFIG.SET_STRING, cast(void*) "on".toStringz()),
        ];
        FSMount("overlay", this.mergedDir(), prop).mount();
    }

    void chown(int uid, int gid, string relpath = "/")
    {
        foreach (string path; dirEntries(this.joinPath(this.mergedDir, relpath), SpanMode.shallow, false))
        {
            _chown(path.toStringz(), uid, gid);
        }
    }

private:
    static const string relUpperDir = "upper";
    static const string relWorkDir = "work";
    static const string relMergedDir = "merged";

    string upperDir() const pure @property
    {
        return this.joinPath(this.baseDir, this.relUpperDir);
    }

    string workDir() const pure @property
    {
        return this.joinPath(this.baseDir, this.relWorkDir);
    }

    static string joinPath(string base, string child) pure
    {
        return base ~ "/" ~ child;
    }
}
