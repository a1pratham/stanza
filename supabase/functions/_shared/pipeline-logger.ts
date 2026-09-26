// Stanza Phase 9 -- pipeline run logging.
//
// Persists a row per invocation of ingest/summarize into pipeline_runs,
// so run history survives past Dashboard Logs' retention/search
// limitations. Usage: call start() at the top of the function, finish()
// right before returning -- on both the success and error paths.

export interface RunHandle {
  runId: string;
  startedAt: string;
}

export async function startRun(supabase: any, functionName: string): Promise<RunHandle> {
  const startedAt = new Date().toISOString();

  const { data, error } = await supabase
    .from('pipeline_runs')
    .insert({ function_name: functionName, started_at: startedAt })
    .select('run_id')
    .single();

  if (error) {
    // Logging failure should never block the actual pipeline work.
    console.error('Failed to start pipeline_runs record:', error.message);
    return { runId: '', startedAt };
  }

  return { runId: data.run_id, startedAt };
}

export async function finishRun(
  supabase: any,
  handle: RunHandle,
  outcome: {
    succeeded?: number;
    failed?: number;
    skipped?: number;
    details?: unknown;
    error?: string;
  },
): Promise<void> {
  if (!handle.runId) return; // startRun already failed; nothing to update

  const { error } = await supabase
    .from('pipeline_runs')
    .update({
      finished_at: new Date().toISOString(),
      succeeded: outcome.succeeded ?? 0,
      failed: outcome.failed ?? 0,
      skipped: outcome.skipped ?? 0,
      details: outcome.details ?? null,
      error: outcome.error ?? null,
    })
    .eq('run_id', handle.runId);

  if (error) {
    console.error('Failed to finish pipeline_runs record:', error.message);
  }
}
