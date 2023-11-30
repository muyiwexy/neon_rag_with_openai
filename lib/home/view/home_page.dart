import 'package:flutter/material.dart';
import 'package:neon_rag_with_openai/home/controller/index_notifier.dart';
import 'package:neon_rag_with_openai/home/controller/query_notifier.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final queryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    IndexNotifier indexNotifierProvider = Provider.of<IndexNotifier>(context);
    QueryNotifier queryNotifierProvider = Provider.of<QueryNotifier>(context);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: kToolbarHeight * 2,
          actions: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.3,
                child: ValueListenableBuilder<IndexState>(
                  valueListenable: indexNotifierProvider.indexState,
                  builder: (BuildContext context, value, Widget? child) {
                    return ElevatedButton(
                      onPressed: () {
                        IndexNotifier indexNotifierProvider =
                            Provider.of<IndexNotifier>(context, listen: false);
                        indexNotifierProvider.indexingNeonTable();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          value == IndexState.initial
                              ? const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 40,
                                )
                              : value == IndexState.loaded
                                  ? const Icon(
                                      Icons.check_outlined,
                                      color: Colors.white,
                                      size: 40,
                                    )
                                  : const CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                          const Text(
                            "ADD",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        ),
        body: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: queryController,
                decoration: InputDecoration(
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(width: 2.0)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          width: 2.0, color: Colors.purple.shade900)),
                  hintText: "Enter your query",
                  label: const Text("Query"),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.02,
              ),
              ElevatedButton(
                  onPressed: () {
                    queryNotifierProvider
                        .queryIngeonTable(queryController.text);
                    queryController.clear();
                  },
                  child: const Text("ASK")),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.02,
              ),
              Expanded(
                child: ValueListenableBuilder<List<Message>>(
                  valueListenable: queryNotifierProvider.messageState,
                  builder:
                      (BuildContext context, dynamic message, Widget? child) {
                    return Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 19,
                          ),
                        ],
                        color: Colors.white,
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 20.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 30,
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding:
                                            const EdgeInsets.only(left: 16.0),
                                        child: Text(
                                          message[index].query!,
                                          style: const TextStyle(
                                              fontSize: 18, letterSpacing: 0.8),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                Card(
                                  color: const Color(0xfff3f6fc),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.all(16.0),
                                    width: MediaQuery.of(context).size.width,
                                    child: message[index].response!.isEmpty
                                        ? const CircularProgressIndicator()
                                        : Text(
                                            message[index].response!,
                                            style:
                                                const TextStyle(fontSize: 18.0),
                                          ),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                        itemCount: message.length,
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
