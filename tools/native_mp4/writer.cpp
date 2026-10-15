#include <godot_cpp/classes/movie_writer.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cstdio>
#include <cstdint>
#include <csignal>
#include <string>
#include <unistd.h>
using namespace godot;

// MovieWriter supplies one deterministic block of audio per rendered frame.
// Video is encoded once; only the small PCM soundtrack is temporarily spooled.
class AbilityMP4Writer : public MovieWriter {
    GDCLASS(AbilityMP4Writer, MovieWriter)
    FILE *video = nullptr, *audio = nullptr;
    std::string output, video_path, audio_path, ffmpeg;
    uint32_t fps = 60, frames = 0;
    bool failed = false;
    static std::string quote(const std::string &s) {
        std::string r = "'";
        for (char c : s) r += c == '\'' ? "'\\''" : std::string(1, c);
        return r + "'";
    }
    static std::string utf8(const String &s) { return s.utf8().get_data(); }
protected:
    static void _bind_methods() {}
public:
    uint32_t _get_audio_mix_rate() const override { return 48000; }
    AudioServer::SpeakerMode _get_audio_speaker_mode() const override { return AudioServer::SPEAKER_MODE_STEREO; }
    bool _handles_file(const String &path) const override { return path.get_extension().to_lower() == "mp4"; }
    PackedStringArray _get_supported_extensions() const override { PackedStringArray a; a.push_back("mp4"); return a; }
    Error _write_begin(const Vector2i &size, uint32_t rate, const String &path) override {
        fps = rate;
        if (48000 % fps) return ERR_INVALID_PARAMETER;
        output = utf8(ProjectSettings::get_singleton()->globalize_path(path));
        video_path = output + ".video.mp4";
        audio_path = output + ".audio.s32le";
        ffmpeg = utf8(OS::get_singleton()->get_environment("FFMPEG_BIN"));
        if (ffmpeg.empty()) ffmpeg = "ffmpeg";
        audio = fopen(audio_path.c_str(), "wb");
        if (!audio) return ERR_CANT_CREATE;
        // Broken encoder pipes become errors, never a silent truncated final file.
        signal(SIGPIPE, SIG_IGN);
        std::string command = quote(ffmpeg) + " -nostdin -hide_banner -loglevel error -y -f rawvideo -pixel_format rgb24 -video_size "
            + std::to_string(size.x) + "x" + std::to_string(size.y) + " -framerate " + std::to_string(fps)
            + " -i pipe:0 -an -c:v libx264 -threads 4 -preset veryfast -crf 18 -pix_fmt yuv420p " + quote(video_path);
        video = popen(command.c_str(), "w");
        if (!video) { fclose(audio); audio = nullptr; return ERR_CANT_CREATE; }
        return OK;
    }
    Error _write_frame(const Ref<Image> &frame, const void *audio_block) override {
        if (failed || !video || !audio) return ERR_FILE_CANT_WRITE;
        frame->convert(Image::FORMAT_RGB8);
        auto pixels = frame->get_data();
        size_t audio_bytes = (48000 / fps) * 2 * sizeof(int32_t);
        if (fwrite(pixels.ptr(), 1, pixels.size(), video) != size_t(pixels.size()) ||
            fwrite(audio_block, 1, audio_bytes, audio) != audio_bytes) {
            failed = true;
            return ERR_FILE_CANT_WRITE;
        }
        ++frames;
        return OK;
    }
    void _write_end() override {
        if (audio) { if (fclose(audio)) failed = true; audio = nullptr; }
        if (video) { if (pclose(video)) failed = true; video = nullptr; }
        if (!frames || failed) { UtilityFunctions::push_error("MP4 encoder failed; final file was not published"); return; }
        std::string pending = output + ".pending.mp4";
        std::string command = quote(ffmpeg) + " -nostdin -hide_banner -loglevel error -y -i " + quote(video_path)
            + " -f s32le -ar 48000 -ac 2 -i " + quote(audio_path)
            + " -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 192k -af alimiter=limit=0.89:level=false:latency=true -movflags +faststart "
            + quote(pending);
        if (std::system(command.c_str()) || std::rename(pending.c_str(), output.c_str())) {
            failed = true; UtilityFunctions::push_error("MP4 audio mux failed; intermediate files retained"); return;
        }
        std::remove(video_path.c_str()); std::remove(audio_path.c_str());
        UtilityFunctions::print("ABILITY_MP4_COMPLETE frames=", frames, " fps=", fps);
    }
};
static AbilityMP4Writer *writer = nullptr;
static void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<AbilityMP4Writer>();
    writer = memnew(AbilityMP4Writer);
    MovieWriter::add_writer(writer);
}
static void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT ability_mp4_init(GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize); init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
