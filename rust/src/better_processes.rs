use std::io::{Read, Write};
use std::process::Stdio;
use std::process::{Child, Command};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::thread::{self, JoinHandle};

use godot::engine::Engine;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base = Node)]
pub struct ProcessNode {
    #[export]
    pub start_on_ready: bool,
    #[export]
    pub cmd: GodotString,
    #[export]
    pub args: PackedStringArray,

    raw_process: Option<RawProcess>,
    #[base]
    base: Base<Node>,
}

#[godot_api]
pub impl NodeVirtual for ProcessNode {
    fn init(base: Base<Node>) -> Self {
        Self {
            start_on_ready: false,
            cmd: GodotString::from(""),
            args: PackedStringArray::new(),
            raw_process: None,
            base,
        }
    }
    fn ready(&mut self) {
        if Engine::singleton().is_editor_hint() {
            return;
        }
        if self.start_on_ready {
            let return_string = self.start();
            if return_string != "".into() {
                godot_print!("{}", return_string);
            }
        }
    }
    fn process(&mut self, _delta: f64) {
        if let Some(mut raw_process) = self.raw_process.take() {
            let out = raw_process.read_stdout();
            if !out.is_empty() {
                self.base.emit_signal(
                    "stdout".into(),
                    &[
                        PackedByteArray::from_iter(out).to_variant(),
                        self.cmd.to_variant(),
                        self.args.to_variant(),
                    ],
                );
            }
            let err = raw_process.read_stderr();
            if !err.is_empty() {
                self.base.emit_signal(
                    "stderr".into(),
                    &[
                        PackedByteArray::from_iter(err).to_variant(),
                        self.cmd.to_variant(),
                        self.args.to_variant(),
                    ],
                );
            }
            self.raw_process = if raw_process.is_running() {
                Some(raw_process)
            } else {
                let a = raw_process.child.wait().unwrap().code().unwrap();
                self.base.emit_signal(
                    "finished".into(),
                    &[
                        Variant::from(a),
                        self.cmd.to_variant(),
                        self.args.to_variant(),
                    ],
                );
                self.queue_free();
                None
            };
        }
    }
}

#[godot_api]
pub impl ProcessNode {
    #[func]
    fn start(&mut self) -> GodotString {
        //start cmd
        let cmd = self.cmd.to_string();
        let args: Vec<String> = self
            .args
            .to_vec()
            .iter()
            .map(|i: &GodotString| i.to_string())
            .collect();
        let rp = match RawProcess::new(cmd, args) {
            Ok(rp) => rp,
            Err(error) => return error.to_string().into(),
        };
        self.raw_process = Some(rp);
        "".into()
    }

    #[func]
    fn write_stdin(&mut self, s: PackedByteArray) {
        match self.raw_process.take() {
            Some(rp) => {
                rp.write(s.to_vec().as_slice());
                self.raw_process = Some(rp);
            }
            _ => {
                godot_error!("Can't write to closed process!");
            }
        }
    }

    // #[func]
    // fn qwer(&mut self){
    // }

    #[signal]
    fn stdout();
    #[signal]
    fn stderr();
    #[signal]
    fn finished();
}

struct RawProcess {
    stdin_tx: Sender<u8>,
    stdout_rx: Receiver<u8>,
    stderr_rx: Receiver<u8>,
    handle_stdout: JoinHandle<Result<(), String>>,
    _handle_stderr: JoinHandle<Result<(), String>>,
    _handle_stdin: JoinHandle<Result<(), String>>,
    child: Child,
}

impl RawProcess {
    fn new(cmd: String, args: Vec<String>) -> Result<Self, std::io::Error> {
        let (stdout_tx, stdout_rx) = channel();
        let (stderr_tx, stderr_rx) = channel();
        let (stdin_tx, stdin_rx) = channel();
        let mut child = match Command::new(cmd)
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::piped())
            .spawn()
        {
            Ok(child) => child,
            Err(error) => return Err(error),
        };

        let handle_stdout = {
            let stdout_tx = stdout_tx.clone();
            let stdout = child.stdout.take();
            thread::spawn(move || match stdout {
                Some(stdout) => {
                    for i in stdout.bytes() {
                        let _ = stdout_tx.send(i.unwrap());
                    }
                    Ok(())
                }
                None => Err("StdOut didn't init correctly".into()),
            })
        };

        let handle_stdin = {
            let stdin = child.stdin.take();
            thread::spawn(move || {
                //this maybe needs to migrate to the above scope so we can process the handles correctly
                let mut a = stdin.unwrap();
                stdin_rx.iter().for_each(|v| {
                    let _ = a.write(&[v]);
                    let _ = a.flush(); //this pipe should throw Vec<Vec<u8>> and flush full Vec<u8> all at once
                });
                Ok(())
            })
        };

        let stderr = child.stderr.take();
        let stderr_tx = stderr_tx.clone();
        let handle_stderr = thread::spawn(move || match stderr {
            Some(stderr) => {
                for i in stderr.bytes() {
                    let _ = stderr_tx.send(i.unwrap());
                }
                Ok(())
            }
            None => Err("StdErr didn't init correctly".into()),
        });

        Ok(Self {
            stdout_rx,
            stderr_rx,
            stdin_tx,
            handle_stdout,
            _handle_stderr: handle_stderr,
            _handle_stdin: handle_stdin,
            child,
        })
    }
    fn write(&self, text: &[u8]) {
        //should this be a str? u8 array?
        text.iter().for_each(|i| {
            let _ = self.stdin_tx.send(*i);
        })
    }
    fn read_stderr(&self) -> Vec<u8> {
        self.stderr_rx.try_iter().collect()
    }
    fn read_stdout(&self) -> Vec<u8> {
        self.stdout_rx.try_iter().collect()
    }
    fn is_running(&self) -> bool {
        !self.handle_stdout.is_finished()
    }
}

impl Drop for RawProcess {
    fn drop(&mut self) {
        let _ = self.child.kill();
    }
}
