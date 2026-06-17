-- ============================================================
-- PLANEJA SEMEC - SQL COMPLETO
-- Departamento de Planejamento, Captação de Recursos, MP,
-- Conselhos, Pareceres, Relatórios e Sistemas Oficiais.
--
-- Como usar:
-- 1. Abra o Supabase.
-- 2. Vá em SQL Editor > New query.
-- 3. Cole todo este conteúdo.
-- 4. Clique em Run.
-- 5. Depois crie os usuários em Authentication > Users.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text default 'usuario' check (role in ('admin', 'gestor', 'usuario')),
  created_at timestamptz default now()
);

create table if not exists public.processes (
  id uuid primary key default gen_random_uuid(),
  numero_interno text,
  data_entrada date not null default current_date,
  tipo text not null check (tipo in (
    'CAPTACAO_RECURSOS',
    'MP_ORGAOS_CONTROLE',
    'CONSELHOS',
    'PARECER_RELATORIO',
    'SISTEMAS_OFICIAIS',
    'PLANEJAMENTO',
    'DOCUMENTO_TECNICO'
  )),
  origem text,
  assunto text not null,
  descricao text,
  prioridade text not null default 'Média' check (prioridade in ('Urgente', 'Alta', 'Média', 'Baixa')),
  prazo_oficial date,
  prazo_interno date,
  responsavel text,
  setor_envolvido text,
  status text not null default 'Novo' check (status in (
    'Novo',
    'Classificado',
    'Em elaboração',
    'Aguardando informações',
    'Aguardando revisão do André',
    'Aguardando assinatura',
    'Enviado/Protocolado',
    'Concluído',
    'Arquivado',
    'Suspenso'
  )),
  link_drive text,
  data_conclusao date,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.task_templates (
  id uuid primary key default gen_random_uuid(),
  process_type text not null,
  title text not null,
  sort_order integer not null default 1,
  required boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.process_tasks (
  id uuid primary key default gen_random_uuid(),
  process_id uuid not null references public.processes(id) on delete cascade,
  template_id uuid references public.task_templates(id) on delete set null,
  title text not null,
  sort_order integer not null default 1,
  required boolean not null default true,
  done boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists public.process_notes (
  id uuid primary key default gen_random_uuid(),
  process_id uuid not null references public.processes(id) on delete cascade,
  note text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  process_id uuid references public.processes(id) on delete set null,
  tipo_documento text not null,
  numero_documento text,
  assunto text,
  link_arquivo text,
  status text default 'Em elaboração',
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create table if not exists public.official_systems (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  finalidade text,
  responsavel text,
  situacao text,
  proximo_prazo date,
  observacoes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  inep text,
  diretor text,
  telefone text,
  endereco text,
  zona text check (zona in ('Urbana', 'Rural') or zona is null),
  tipo_unidade text,
  observacoes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_processes_updated_at on public.processes;
create trigger set_processes_updated_at
before update on public.processes
for each row execute function public.set_updated_at();

drop trigger if exists set_official_systems_updated_at on public.official_systems;
create trigger set_official_systems_updated_at
before update on public.official_systems
for each row execute function public.set_updated_at();

drop trigger if exists set_schools_updated_at on public.schools;
create trigger set_schools_updated_at
before update on public.schools
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email), 'usuario')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.processes enable row level security;
alter table public.task_templates enable row level security;
alter table public.process_tasks enable row level security;
alter table public.process_notes enable row level security;
alter table public.documents enable row level security;
alter table public.official_systems enable row level security;
alter table public.schools enable row level security;

drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles for select to authenticated using (true);

drop policy if exists "processes_select" on public.processes;
create policy "processes_select" on public.processes for select to authenticated using (true);

drop policy if exists "processes_insert" on public.processes;
create policy "processes_insert" on public.processes for insert to authenticated with check (true);

drop policy if exists "processes_update" on public.processes;
create policy "processes_update" on public.processes for update to authenticated using (true) with check (true);

drop policy if exists "processes_delete" on public.processes;
create policy "processes_delete" on public.processes for delete to authenticated using (true);

drop policy if exists "templates_manage" on public.task_templates;
create policy "templates_manage" on public.task_templates for all to authenticated using (true) with check (true);

drop policy if exists "tasks_manage" on public.process_tasks;
create policy "tasks_manage" on public.process_tasks for all to authenticated using (true) with check (true);

drop policy if exists "notes_manage" on public.process_notes;
create policy "notes_manage" on public.process_notes for all to authenticated using (true) with check (true);

drop policy if exists "documents_manage" on public.documents;
create policy "documents_manage" on public.documents for all to authenticated using (true) with check (true);

drop policy if exists "systems_manage" on public.official_systems;
create policy "systems_manage" on public.official_systems for all to authenticated using (true) with check (true);

drop policy if exists "schools_manage" on public.schools;
create policy "schools_manage" on public.schools for all to authenticated using (true) with check (true);

-- Realtime para atualização em vários computadores.
-- Se aparecer aviso dizendo que a tabela já está na publicação, pode ignorar.
do $$
begin
  begin alter publication supabase_realtime add table public.processes; exception when others then null; end;
  begin alter publication supabase_realtime add table public.process_tasks; exception when others then null; end;
  begin alter publication supabase_realtime add table public.process_notes; exception when others then null; end;
end $$;

-- Limpa e insere tarefas padrão.
delete from public.task_templates;
insert into public.task_templates (process_type, title, sort_order, required) values
('CAPTACAO_RECURSOS','Identificar fonte do recurso: SIMEC, PAR, FNDE, emenda, convênio ou programa.',1,true),
('CAPTACAO_RECURSOS','Levantar diagnóstico da necessidade: escola, quantidade, público atendido e justificativa.',2,true),
('CAPTACAO_RECURSOS','Separar documentos obrigatórios: ofício, fotos, dados da rede, cotações ou declarações.',3,true),
('CAPTACAO_RECURSOS','Elaborar justificativa técnica para captação.',4,true),
('CAPTACAO_RECURSOS','Enviar para revisão do André.',5,true),
('CAPTACAO_RECURSOS','Protocolar/submeter no sistema ou encaminhar ao órgão responsável.',6,true),
('CAPTACAO_RECURSOS','Arquivar comprovante de envio e registrar próximo acompanhamento.',7,true),
('MP_ORGAOS_CONTROLE','Registrar ofício, recomendação, notificação ou requisição recebida.',1,true),
('MP_ORGAOS_CONTROLE','Identificar prazo oficial de resposta e criar prazo interno anterior.',2,true),
('MP_ORGAOS_CONTROLE','Levantar informações com setores envolvidos.',3,true),
('MP_ORGAOS_CONTROLE','Separar documentos comprobatórios e evidências.',4,true),
('MP_ORGAOS_CONTROLE','Elaborar relatório técnico, resposta ou manifestação.',5,true),
('MP_ORGAOS_CONTROLE','Enviar para revisão do André.',6,true),
('MP_ORGAOS_CONTROLE','Colher assinatura/autorização e protocolar resposta.',7,true),
('MP_ORGAOS_CONTROLE','Arquivar resposta protocolada e comprovante.',8,true),
('CONSELHOS','Identificar conselho: CME, CAE, CACS-FUNDEB ou outro.',1,true),
('CONSELHOS','Registrar assunto, reunião, pauta ou solicitação.',2,true),
('CONSELHOS','Separar atas, resoluções, pareceres ou documentos de apoio.',3,true),
('CONSELHOS','Preparar minuta de parecer, ata, resolução ou relatório.',4,true),
('CONSELHOS','Enviar para conferência e assinatura dos responsáveis.',5,true),
('CONSELHOS','Arquivar versão final assinada.',6,true),
('PARECER_RELATORIO','Definir objetivo do documento técnico.',1,true),
('PARECER_RELATORIO','Coletar dados, legislação, documentos e evidências.',2,true),
('PARECER_RELATORIO','Estruturar diagnóstico, análise e conclusão.',3,true),
('PARECER_RELATORIO','Redigir parecer, relatório ou nota técnica.',4,true),
('PARECER_RELATORIO','Enviar para revisão do André.',5,true),
('PARECER_RELATORIO','Finalizar versão em PDF e arquivar.',6,true),
('SISTEMAS_OFICIAIS','Identificar sistema: SIMEC, PAR, FNDE, INEP, PDDE, PNAE ou outro.',1,true),
('SISTEMAS_OFICIAIS','Verificar pendência, diligência ou janela de preenchimento.',2,true),
('SISTEMAS_OFICIAIS','Separar dados e documentos necessários.',3,true),
('SISTEMAS_OFICIAIS','Realizar preenchimento/atualização no sistema.',4,true),
('SISTEMAS_OFICIAIS','Salvar comprovante, protocolo ou print da tela.',5,true),
('SISTEMAS_OFICIAIS','Registrar próximo prazo de acompanhamento.',6,true),
('PLANEJAMENTO','Definir problema, meta ou demanda de planejamento.',1,true),
('PLANEJAMENTO','Levantar dados da rede, escolas, matrículas, transporte ou programas.',2,true),
('PLANEJAMENTO','Organizar diagnóstico e proposta de ação.',3,true),
('PLANEJAMENTO','Elaborar plano, cronograma ou relatório.',4,true),
('PLANEJAMENTO','Validar com André e encaminhar ao setor responsável.',5,true),
('DOCUMENTO_TECNICO','Identificar tipo de documento: ofício, declaração, despacho, justificativa ou memorando.',1,true),
('DOCUMENTO_TECNICO','Confirmar dados obrigatórios: nomes, datas, assunto, destinatário e fundamento.',2,true),
('DOCUMENTO_TECNICO','Redigir minuta no padrão institucional.',3,true),
('DOCUMENTO_TECNICO','Enviar para revisão/assinatura.',4,true),
('DOCUMENTO_TECNICO','Gerar PDF, enviar e arquivar versão final.',5,true);
