use iced::{button, Align, Button, Column, Element, Sandbox, Settings, Text};

use std::fs::File;
use std::fs;
use std::path;
use std::io::BufReader;
use rodio::{Decoder, OutputStream, source::Source, Sink};

pub fn main() {

    let paths = fs::read_dir("music").unwrap();
    for path in paths {
        let p = path.unwrap().path();

        println!("Name: {}", p.display());
        play_track(p)
    }
}

fn play_track(track: path::PathBuf) {
    // Get a output stream handle to the default physical sound device
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    // Load a sound from a file, using a path relative to Cargo.toml
    let file = BufReader::new(File::open(track).unwrap());
    // Decode that sound file into a source
    let source = Decoder::new(file).unwrap();
    // Play the sound directly on the device
    // stream_handle.play_raw(source.convert_samples());

    // The sound plays in a separate audio thread,
    // so we need to keep the main thread alive while it's playing.
    // std::thread::sleep(std::time::Duration::from_secs(5));

    let sink = Sink::try_new(&stream_handle).unwrap();
    sink.append(source);

    // The sound plays in a separate thread. This call will block the current thread until the sink
    // has finished playing all its queued sounds.
    sink.sleep_until_end();
}

// pub fn main() -> iced::Result {
//     Counter::run(Settings::default())
// }

#[derive(Default)]
struct Counter {
    value: i32,
    increment_button: button::State,
    decrement_button: button::State,
}

#[derive(Debug, Clone, Copy)]
enum Message {
    IncrementPressed,
    DecrementPressed,
}

impl Sandbox for Counter {
    type Message = Message;

    fn new() -> Self {
        Self::default()
    }

    fn title(&self) -> String {
        String::from("Counter - Iced")
    }

    fn update(&mut self, message: Message) {
        match message {
            Message::IncrementPressed => {
                self.value += 1;
            }
            Message::DecrementPressed => {
                self.value -= 1;
            }
        }
    }

    fn view(&mut self) -> Element<Message> {

                Button::new(&mut self.increment_button, Text::new(self.value.to_string()).size(50))
                    .on_press(Message::IncrementPressed)
            .into()
    }
}
